using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddReminders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Hatirlaticilar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Baslik = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Not = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    Tur = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Kime = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Gun = table.Column<DateOnly>(type: "date", nullable: false),
                    Saat = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    Tekrar = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    OnceGun = table.Column<int>(type: "integer", nullable: false),
                    Durum = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    SonrakiAn = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ErteleAn = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Hatirlaticilar", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Hatirlaticilar_Durum_SonrakiAn",
                table: "Hatirlaticilar",
                columns: new[] { "Durum", "SonrakiAn" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Hatirlaticilar");
        }
    }
}
