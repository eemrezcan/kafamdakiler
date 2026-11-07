using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddGelenKartlari : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GelenKartlari",
                columns: table => new
                {
                    Kart = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    LaptoptaIslenecek = table.Column<bool>(type: "boolean", nullable: false),
                    LaptopNotu = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    DenemeSayisi = table.Column<int>(type: "integer", nullable: false),
                    SonDenemeAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    SonHata = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    OneriAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GelenKartlari", x => x.Kart);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GelenKartlari");
        }
    }
}
