using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddBrifing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BrifingOylari",
                columns: table => new
                {
                    Gun = table.Column<DateOnly>(type: "date", nullable: false),
                    Sira = table.Column<int>(type: "integer", nullable: false),
                    Tur = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Oy = table.Column<int>(type: "integer", nullable: false),
                    Zaman = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BrifingOylari", x => new { x.Gun, x.Sira });
                });

            migrationBuilder.CreateTable(
                name: "Brifingler",
                columns: table => new
                {
                    Gun = table.Column<DateOnly>(type: "date", nullable: false),
                    Kartlar = table.Column<string>(type: "jsonb", nullable: false),
                    UretimAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Yontem = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    YenilemeSayisi = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Brifingler", x => x.Gun);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BrifingOylari");

            migrationBuilder.DropTable(
                name: "Brifingler");
        }
    }
}
